pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    required property var hud
    readonly property var estimator: hud.vehicle ? hud.vehicle.estimatorStatus : null
    readonly property var vibration: hud.vehicle ? hud.vehicle.vibration : null
    readonly property var ratioFields: [
        {key: "velRatio", name: qsTr("速度")}, {key: "horizPosRatio", name: qsTr("水平位置")},
        {key: "vertPosRatio", name: qsTr("垂直位置")}, {key: "magRatio", name: qsTr("罗盘")},
        {key: "haglRatio", name: qsTr("地形高度")}, {key: "tasRatio", name: qsTr("空速")}
    ]
    readonly property var flagFields: [
        {key: "goodAttitudeEstimate", name: "attitude"}, {key: "goodHorizVelEstimate", name: "velocity_horiz"},
        {key: "goodVertVelEstimate", name: "velocity_vert"}, {key: "goodHorizPosRelEstimate", name: "pos_horiz_rel"},
        {key: "goodHorizPosAbsEstimate", name: "pos_horiz_abs"}, {key: "goodVertPosAbsEstimate", name: "pos_vert_abs"},
        {key: "goodVertPosAGLEstimate", name: "pos_vert_agl"}, {key: "goodConstPosModeEstimate", name: "const_pos_mode"},
        {key: "goodPredHorizPosRelEstimate", name: "pred_pos_horiz_rel"}, {key: "goodPredHorizPosAbsEstimate", name: "pred_pos_horiz_abs"},
        {key: "gpsGlitch", name: "gps_glitch", failure: true}, {key: "accelError", name: "accel_error", failure: true}
    ]
    function open(kind) { if (kind === "vibration") vibePopup.open(); else ekfPopup.open() }
    function closeAll() { ekfPopup.close(); vibePopup.close() }
    function value(group, key, field) {
        if (!hud.available(field) || !group || !group[key]) return NaN
        const number = Number(group[key].rawValue)
        return isFinite(number) && number >= 0 ? number : NaN
    }

    DiagnosticPopup { id: ekfPopup; objectName: "hudEkfPopup"; vibrationMode: false }
    DiagnosticPopup { id: vibePopup; objectName: "hudVibePopup"; vibrationMode: true }

    component DiagnosticPopup: Popup {
        id: dialog
        property bool vibrationMode: false
        property real revealProgress: 0
        readonly property bool fresh: root.hud.available(vibrationMode ? "vibration" : "estimatorStatus")
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: Math.min(760, parent ? parent.width - 16 : 600)
        height: Math.min(vibrationMode ? 440 : 550, parent ? parent.height - 16 : 480)
        x: parent ? Math.max(8, (parent.width - width) / 2 + (vibrationMode ? 18 : -18)) : 0
        y: parent ? Math.max(8, (parent.height - height) / 2 + (vibrationMode ? 18 : -18)) : 0
        padding: 1
        opacity: revealProgress
        enter: Transition {
            NumberAnimation { target: dialog; property: "revealProgress"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { target: dialog; property: "revealProgress"; to: 0; duration: 140; easing.type: Easing.OutCubic }
        }
        background: Rectangle { color: "#FA20242B"; border.color: "#91A3B4"; radius: 6 }
        onOpened: {
            x = parent ? Math.max(8, Math.min(x, parent.width - width - 8)) : 0
            y = parent ? Math.max(8, Math.min(y, parent.height - height - 8)) : 0
        }
        Connections {
            target: dialog.parent
            function onWidthChanged() { if (dialog.opened) dialog.x = Math.max(0, Math.min(dialog.x, dialog.parent.width - dialog.width)) }
            function onHeightChanged() { if (dialog.opened) dialog.y = Math.max(0, Math.min(dialog.y, dialog.parent.height - dialog.height)) }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(44, ScreenTools.minTouchPixels)
                color: "#344452"
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: ScreenTools.minTouchPixels
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point pressPoint
                    property point origin
                    onPressed: mouse => { pressPoint = mapToItem(dialog.parent, mouse.x, mouse.y); origin = Qt.point(dialog.x, dialog.y) }
                    onPositionChanged: mouse => {
                        if (!pressed || !dialog.parent) return
                        const point = mapToItem(dialog.parent, mouse.x, mouse.y)
                        dialog.x = Math.max(0, Math.min(origin.x + point.x - pressPoint.x, dialog.parent.width - dialog.width))
                        dialog.y = Math.max(0, Math.min(origin.y + point.y - pressPoint.y, dialog.parent.height - dialog.height))
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    QGCLabel { Layout.fillWidth: true; text: dialog.vibrationMode ? qsTr("振动 / Vibration") : qsTr("EKF 状态 / EKF Status"); color: "white"; font.weight: Font.Bold }
                    QGCButton { objectName: dialog.vibrationMode ? "hudVibeClose" : "hudEkfClose"; text: "×"; Layout.preferredWidth: Math.max(44, ScreenTools.minTouchPixels); Layout.fillHeight: true; onClicked: dialog.close(); Accessible.name: qsTr("关闭诊断窗口") }
                }
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                text: !dialog.fresh ? qsTr("未收到当前飞控的实时数据，指标显示 --。") : dialog.vibrationMode ? qsTr("单位 m/s²；30 和 60 为振动参考线。Clipping 为各 IMU 的累计削波计数。") : qsTr("创新检验比率越低越好；0.5 为关注线，0.8 为警戒参考线，1.0 为检验阈值。")
                color: dialog.fresh ? "#D5DCE1" : "#FFD395"
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        spacing: 10
                        Repeater {
                            model: dialog.vibrationMode ? [{key: "xAxis", name: "X"}, {key: "yAxis", name: "Y"}, {key: "zAxis", name: "Z"}] : root.ratioFields
                            delegate: ColumnLayout {
                                id: gauge
                                required property var modelData
                                readonly property real reading: root.value(dialog.vibrationMode ? root.vibration : root.estimator, modelData.key, dialog.vibrationMode ? "vibration" + modelData.name : "estimatorStatus")
                                Layout.fillWidth: true
                                spacing: 5
                                QGCLabel { Layout.alignment: Qt.AlignHCenter; text: root.hud.format(gauge.reading, dialog.vibrationMode ? 1 : 2); color: "white"; font.weight: Font.DemiBold }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 170
                                    color: "#41494E"
                                    border.color: "#7B848A"
                                    gradient: Gradient { GradientStop { position: 0; color: "#62686A" } GradientStop { position: 1; color: "#2B3134" } }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 2
                                        height: isFinite(gauge.reading) ? Math.max(0, Math.min(1, gauge.reading / (dialog.vibrationMode ? 90 : 1.2))) * (parent.height - 4) : 0
                                        color: !isFinite(gauge.reading) ? "transparent" : gauge.reading >= (dialog.vibrationMode ? 60 : 0.8) ? "#ED7268" : gauge.reading >= (dialog.vibrationMode ? 30 : 0.5) ? "#EBD46A" : "#A9D873"
                                    }
                                    Rectangle { x: 0; width: parent.width; height: 1.5; y: parent.height * (1 - (dialog.vibrationMode ? 60 / 90 : 0.8 / 1.2)); color: "#F26961" }
                                    Rectangle { x: 0; width: parent.width; height: 1; y: parent.height * (1 - (dialog.vibrationMode ? 30 / 90 : 0.5 / 1.2)); color: "#E2C970" }
                                }
                                QGCLabel { Layout.fillWidth: true; text: gauge.modelData.name; color: "#DCE4EB"; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                        }
                    }
                    GridLayout {
                        visible: dialog.vibrationMode
                        Layout.fillWidth: true
                        Layout.margins: 12
                        columns: 3
                        Repeater {
                            model: [{key: "clipCount1", label: "IMU 1"}, {key: "clipCount2", label: "IMU 2"}, {key: "clipCount3", label: "IMU 3"}]
                            QGCLabel {
                                required property var modelData
                                Layout.fillWidth: true
                                text: modelData.label + " · Clipping " + root.hud.format(root.value(root.vibration, modelData.key, "vibration"), 0)
                                color: "#D6E4EC"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    QGCLabel {
                        visible: !dialog.vibrationMode
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        text: qsTr("Flags · %1 · 原始位 %2").arg(dialog.fresh && root.estimator ? root.estimator.reportType : "--").arg(dialog.fresh && root.estimator ? root.hud.format(Number(root.estimator.rawFlags.rawValue), 0) : "--")
                        color: "#D2E7F2"
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    GridLayout {
                        visible: !dialog.vibrationMode
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        columns: dialog.width >= 520 ? 2 : 1
                        Repeater {
                            model: root.flagFields
                            QGCLabel {
                                required property var modelData
                                readonly property bool valueKnown: dialog.fresh && !!root.estimator && !!root.estimator[modelData.key] && (modelData.key !== "accelError" || root.estimator.reportType === "ESTIMATOR_STATUS")
                                readonly property bool flag: valueKnown && !!root.estimator[modelData.key].rawValue
                                Layout.fillWidth: true
                                text: modelData.name + "  " + (!valueKnown ? "--" : flag ? "On" : "Off")
                                color: !valueKnown ? "#B3BBC2" : (modelData.failure ? flag : !flag) ? "#FCA095" : "#AFD6A6"
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }
                    }
                    QGCLabel {
                        visible: !dialog.vibrationMode && dialog.fresh && root.estimator && root.estimator.reportType === "EKF_STATUS_REPORT"
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        text: qsTr("ArduPilot · uninitialized %1").arg(root.estimator && (Number(root.estimator.rawFlags.rawValue) & 1024) ? "On" : "Off")
                        color: root.estimator && (Number(root.estimator.rawFlags.rawValue) & 1024) ? "#FCA095" : "#AFD6A6"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }
}
