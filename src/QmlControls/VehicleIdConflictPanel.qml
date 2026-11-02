pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id: root
    required property var conflictManager
    spacing: ScreenTools.defaultFontPixelHeight * 0.5
    implicitWidth: ScreenTools.defaultFontPixelWidth * 44
    QGCPalette { id: palette }

    function requestAssignment(row) {
        const resolver = conflictManager
        const token = String(row.token), oldId = Number(row.systemId), newId = Number(row.newId)
        const port = String(row.port)
        QGroundControl.showMessageDialog(root, qsTr("自动分配飞机编号"),
            qsTr("将 %1 从 %2 号改为 %3 号？\n\n原编号会先保存备份。请确认飞控已锁定；需要重启时会另行提示。")
                .arg(port).arg(oldId).arg(newId), Dialog.Yes | Dialog.No,
            function() { if (resolver) resolver.repair(token, newId) })
    }

    function requestRestart(row) {
        const resolver = conflictManager, token = String(row.token), port = String(row.port)
        QGroundControl.showMessageDialog(root, qsTr("重启指定飞控"),
            qsTr("编号参数已确认。是否重启 %1 并等待自动重连？请确认该飞控已锁定。")
                .arg(port), Dialog.Yes | Dialog.No,
            function() { if (resolver) resolver.restartAssignedController(token) })
    }

    QGCLabel {
        Layout.fillWidth: true
        text: qsTr("飞机编号自动分配")
        font.bold: true
    }
    QGCLabel {
        Layout.fillWidth: true
        visible: root.conflictManager && root.conflictManager.conflicts.length > 0
        wrapMode: Text.WordWrap
        text: qsTr("重复编号的第二路已隔离。地面站会保留原设备编号，给新接入的飞控分配未占用编号。")
        color: palette.warningText
    }
    Repeater {
        model: root.conflictManager ? root.conflictManager.conflicts : []
        delegate: Rectangle {
            id: card
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: cardContent.implicitHeight + ScreenTools.defaultFontPixelHeight
            radius: ScreenTools.defaultBorderRadius
            color: palette.windowShade
            border.color: palette.warningText
            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                QGCLabel { Layout.fillWidth: true; text: card.modelData.port; font.bold: true; elide: Text.ElideMiddle }
                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("当前 %1 号 → 分配 %2 号").arg(card.modelData.systemId).arg(card.modelData.newId)
                }
                QGCLabel {
                    Layout.fillWidth: true
                    visible: !!card.modelData.hardwareShort
                    text: qsTr("硬件标识尾段：%1").arg(card.modelData.hardwareShort)
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel { Layout.fillWidth: true; text: card.modelData.status; wrapMode: Text.WordWrap }
                RowLayout {
                    Layout.fillWidth: true
                    QGCButton {
                        objectName: "assignVehicleId" + card.modelData.token
                        Layout.fillWidth: true
                        text: qsTr("自动分配编号")
                        enabled: card.modelData.canRepair
                        onClicked: root.requestAssignment(card.modelData)
                    }
                    QGCButton {
                        text: qsTr("重新检测")
                        enabled: card.modelData.canRetry && !root.conflictManager.busy
                        onClicked: root.conflictManager.retryProbe(card.modelData.token)
                    }
                }
                QGCButton {
                    objectName: "restartAssignedVehicle" + card.modelData.token
                    Layout.fillWidth: true
                    visible: card.modelData.canRestart
                    text: qsTr("重启这台飞控")
                    onClicked: root.requestRestart(card.modelData)
                }
            }
        }
    }
    QGCLabel {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.conflictManager ? root.conflictManager.lastResult : ""
        visible: text.length > 0
        color: palette.text
    }
}
