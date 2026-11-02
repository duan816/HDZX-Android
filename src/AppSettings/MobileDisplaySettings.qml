import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id: root

    readonly property var _scaleFact: QGroundControl.settingsManager.appSettings.mobileUiScalePercent
    spacing: ScreenTools.defaultFontPixelHeight * 0.6

    QGCLabel {
        Layout.fillWidth: true
        text: qsTr("手机 / 平板显示")
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }

    QGCLabel {
        Layout.fillWidth: true
        text: qsTr("界面预设")
        wrapMode: Text.WordWrap
    }

    QGCComboBox {
        objectName: "mobileUiPreset"
        Layout.fillWidth: true
        model: [qsTr("手机（80%）"), qsTr("平板（100%）"), qsTr("自定义比例")]
        currentIndex: Number(root._scaleFact.rawValue) === 80 ? 0 : Number(root._scaleFact.rawValue) === 100 ? 1 : 2
        onActivated: index => {
            if (index < 2) ScreenTools.applyMobileUiPreset(index === 0 ? 80 : 100)
        }
    }

    QGCLabel {
        Layout.fillWidth: true
        text: qsTr("界面比例：%1%").arg(root._scaleFact.rawValue)
        wrapMode: Text.WordWrap
    }

    QGCSlider {
        objectName: "mobileUiScaleSlider"
        Layout.fillWidth: true
        Layout.minimumHeight: ScreenTools.mobileTouchTarget
        from: root._scaleFact.min
        to: root._scaleFact.max
        stepSize: 1
        value: root._scaleFact.rawValue
        onMoved: ScreenTools.applyMobileUiPreset(value)
    }

    QGCLabel {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        text: qsTr("70%（较小）— 120%（较大）。100% 保留原始安卓比例；字体、导航、按钮和面板会一起调整，立即生效并自动保存。")
        wrapMode: Text.WordWrap
        font.pointSize: ScreenTools.smallFontPointSize
    }
}
