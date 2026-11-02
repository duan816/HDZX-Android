import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Popup {
    id: root

    property var manager: QGroundControl.multiVehicleManager.rebootConnection
    readonly property var progressVehicle: manager ? manager.progressVehicle : null
    readonly property bool waiting: !!manager && manager.active
    readonly property bool communicationLost: !!progressVehicle && !!progressVehicle.vehicleLinkManager
                                             && progressVehicle.vehicleLinkManager.communicationLost

    width: Math.min(parent ? parent.width * 0.85 : 600, ScreenTools.defaultFontPixelWidth * 60)
    modal: false
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    background: Rectangle {
        color: "#F00D2537"
        radius: ScreenTools.defaultFontPixelHeight
        border.color: "#47B8C2"
    }

    function updateVisibility() {
        if (!manager) return
        if (manager.active && !opened) open()
        else if (!manager.active && manager.stage === 3) close()
    }

    Connections {
        target: root.manager
        function onChanged() { root.updateVisibility() }
    }
    Component.onCompleted: updateVisibility()

    contentItem: ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight * 0.7

        QGCLabel {
            text: qsTr("飞控重启与自动重连")
            font.family: ScreenTools.hqUiFontFamily
            font.bold: true
            font.pointSize: ScreenTools.mediumFontPointSize
        }
        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.manager ? root.manager.status : ""
        }
        HQConnectionProgress {
            id: reconnectProgress
            objectName: "rebootConnectionProgress"
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            visible: root.waiting
            connected: root.waiting
            progress: root.progressVehicle ? root.progressVehicle.loadProgress : NaN
            indeterminate: !root.progressVehicle
            communicationLost: root.communicationLost
            sourceToken: root.progressVehicle
            accent: root.communicationLost ? "#ff697a"
                                          : QGroundControl.globalPalette.colorGreen
        }
        QGCLabel {
            Layout.fillWidth: true
            visible: root.waiting
            wrapMode: Text.WordWrap
            text: root.progressVehicle
                  ? (root.communicationLost ? qsTr("通信中断 · 初始化暂停")
                                            : qsTr("飞控初始化 · %1").arg(reconnectProgress.percentageText))
                  : qsTr("等待原飞控上线，尚无初始化进度。")
            font.pointSize: ScreenTools.smallFontPointSize
        }
        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("重启确认 → 等待上线 → 读取参数 → 身份确认。等待期间不会重复重启，不影响其他飞机。")
            font.pointSize: ScreenTools.smallFontPointSize
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            QGCButton {
                text: root.waiting ? qsTr("取消等待") : qsTr("关闭")
                onClicked: {
                    if (root.waiting) root.manager.cancel()
                    root.close()
                }
            }
        }
    }
}
