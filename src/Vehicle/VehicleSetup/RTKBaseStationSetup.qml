import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id: root

    property var rtkSettings: QGroundControl.settingsManager.rtkSettings
    property var autoSettings: QGroundControl.settingsManager.autoConnectSettings
    property var portPaths: QGroundControl.linkManager.serialPorts
    property var portLabels: QGroundControl.linkManager.serialPortStrings
    property int baseMode: rtkSettings.useFixedBasePosition.rawValue
    property string connectionNotice: ""
    property bool configureReceiver: true
    readonly property var configureReceiverModel: ["u-blox F9P / M8P", "Septentrio", "Trimble", "Femtomes", "Unicore UM982（和芯星通）"]
    readonly property var directReceiverModel: ["通用 RTCM/NMEA 直通（Generic Direct）"]
    readonly property bool selectedUnicore: root.configureReceiver && receiverCombo.currentText.indexOf("UM982") >= 0
    readonly property real mobileMinimumContentWidth: ScreenTools.defaultFontPixelWidth * 76

    function refreshPorts() {
        portPaths = QGroundControl.linkManager.serialPorts
        portLabels = QGroundControl.linkManager.serialPortStrings
        if (portCombo.currentIndex < 0 && portLabels.length > 0) {
            portCombo.currentIndex = 0
        }
    }

    Connections {
        target: QGroundControl.linkManager
        function onCommPortsChanged() { root.refreshPorts() }
        function onCommPortStringsChanged() { root.refreshPorts() }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCFlickable {
        id: rtkFlick
        anchors.fill: parent
        contentWidth: pageColumn.width
        contentHeight: pageColumn.implicitHeight + ScreenTools.defaultFontPixelHeight
        flickableDirection: Flickable.AutoFlickIfNeeded
        clip: true

        ScrollIndicator.horizontal: ScrollIndicator { }
        ScrollIndicator.vertical: ScrollIndicator { }

        ColumnLayout {
            id: pageColumn
            width: ScreenTools.isMobile
                   ? Math.max(rtkFlick.width, root.mobileMinimumContentWidth)
                   : Math.min(rtkFlick.width, ScreenTools.defaultFontPixelWidth * 90)
            spacing: ScreenTools.defaultFontPixelHeight

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("RTK 基准站连接（RTK Base Station）")
                font.pointSize: ScreenTools.largeFontPointSize
                font.weight: Font.DemiBold
            }

            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("可让 HQGroundControl 自动识别兼容的 USB RTK 接收机，也可以手动选择串口和接收机类型。连接后，基准站输出的 RTCM 改正数据会通过 MAVLink 转发给飞行器。")
            }

            SettingsGroupLayout {
                Layout.fillWidth: true
                heading: qsTr("连接方式（Connection）")

                RowLayout {
                    Layout.fillWidth: true

                    QGCRadioButton {
                        text: qsTr("连接并自动配置（Configure Receiver）")
                        checked: root.configureReceiver
                        onClicked: {
                            root.configureReceiver = true
                            receiverCombo.currentIndex = 0
                        }
                    }
                    QGCRadioButton {
                        text: qsTr("直接连接，不修改接收机（Direct Connection）")
                        checked: !root.configureReceiver
                        onClicked: {
                            root.configureReceiver = false
                            autoSettings.autoConnectRTKGPS.rawValue = false
                            receiverCombo.currentIndex = 0
                        }
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: qgcPal.warningText
                    visible: !root.configureReceiver
                    text: qsTr("直接连接只读取接收机当前输出的 RTCM/状态数据，不发送 Survey-In、固定坐标、输出协议或波特率配置命令。请确认接收机已经配置为输出兼容数据。")
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true
                    visible: root.configureReceiver
                    text: qsTr("自动识别并连接 RTK 接收机（Auto Connect）")
                    fact: autoSettings.autoConnectRTKGPS
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: ScreenTools.defaultFontPixelWidth * 2
                    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel { text: qsTr("串口（Serial Port）") }
                    QGCComboBox {
                        id: portCombo
                        Layout.fillWidth: true
                        model: root.portLabels
                    }

                    QGCLabel { text: qsTr("接收机（Receiver）") }
                    QGCComboBox {
                        id: receiverCombo
                        Layout.fillWidth: true
                        model: root.configureReceiver ? root.configureReceiverModel : root.directReceiverModel
                    }

                    QGCLabel {
                        visible: !root.configureReceiver
                        text: qsTr("波特率（Baud Rate）")
                    }
                    QGCComboBox {
                        id: directBaudCombo
                        Layout.fillWidth: true
                        visible: !root.configureReceiver
                        model: ["9600", "38400", "57600", "115200", "230400", "460800", "921600"]
                        currentIndex: 3
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    QGCButton {
                        text: qsTr("刷新串口")
                        onClicked: root.refreshPorts()
                    }
                    QGCButton {
                        text: root.configureReceiver ? qsTr("连接并配置") : qsTr("直接连接")
                        enabled: !QGroundControl.gpsRtk.connected.value && !QGroundControl.gpsRtk.connecting.value && portCombo.currentIndex >= 0 && portCombo.currentIndex < root.portPaths.length
                        onClicked: {
                            const baudRate = parseInt(directBaudCombo.currentText)
                            const ok = QGroundControl.linkManager.connectRTKSerial(root.portPaths[portCombo.currentIndex], receiverCombo.currentText,
                                                                                  root.configureReceiver, baudRate)
                            root.connectionNotice = ok
                                    ? (root.configureReceiver ? qsTr("正在打开接收机并应用基准站配置……")
                                                              : qsTr("正在直接打开接收机，不修改其现有配置……"))
                                    : qsTr("连接失败：串口不存在、正被占用或无法打开。")
                        }
                    }
                    QGCButton {
                        text: qsTr("断开")
                        enabled: QGroundControl.gpsRtk.connected.value || QGroundControl.gpsRtk.connecting.value
                        onClicked: {
                            QGroundControl.linkManager.disconnectRTKSerial()
                            root.connectionNotice = qsTr("已断开 RTK 基准站。")
                        }
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: QGroundControl.gpsRtk.lastError.rawValue === 0 ? qgcPal.text : qgcPal.warningText
                    text: QGroundControl.gpsRtk.lastError.rawValue !== 0
                            ? qsTr("连接错误：%1").arg(QGroundControl.gpsRtk.lastError.enumStringValue)
                            : QGroundControl.gpsRtk.connecting.value
                            ? qsTr("正在打开串口，请等待 USB 授权及连接结果……")
                            : QGroundControl.gpsRtk.connected.value
                            ? (QGroundControl.gpsRtk.rtcmFrames.rawValue > 0
                               ? qsTr("已收到有效 RTCM：%1；最近消息 RTCM%2")
                                     .arg(QGroundControl.gpsRtk.rtcmFrames.rawValue)
                                     .arg(QGroundControl.gpsRtk.lastRtcmMessageId.rawValue)
                               : (QGroundControl.gpsRtk.streamBytes.rawValue > 0
                                  ? qsTr("串口已有数据，但尚未识别到有效 RTCM。请检查波特率和接收机输出协议。")
                                  : qsTr("串口已打开，正在等待接收机数据：%1").arg(QGroundControl.linkManager.rtkSerialPort)))
                            : root.connectionNotice
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth: true
                heading: qsTr("基准站自动配置（Base Configuration）")
                visible: root.configureReceiver && !root.selectedUnicore

                RowLayout {
                    QGCRadioButton {
                        text: qsTr("自动测量（Survey-In）")
                        checked: root.baseMode === BaseModeDefinition.BaseSurveyIn
                        onClicked: rtkSettings.useFixedBasePosition.rawValue = BaseModeDefinition.BaseSurveyIn
                    }
                    QGCRadioButton {
                        text: qsTr("已知坐标（Fixed Position）")
                        checked: root.baseMode === BaseModeDefinition.BaseFixed
                        onClicked: rtkSettings.useFixedBasePosition.rawValue = BaseModeDefinition.BaseFixed
                    }
                }

                LabelledFactTextField {
                    label: qsTr("目标精度（Survey-In Accuracy）")
                    fact: rtkSettings.surveyInAccuracyLimit
                    visible: root.baseMode === BaseModeDefinition.BaseSurveyIn
                }
                LabelledFactTextField {
                    label: qsTr("最短观测时间（Minimum Duration）")
                    fact: rtkSettings.surveyInMinObservationDuration
                    visible: root.baseMode === BaseModeDefinition.BaseSurveyIn
                }
                LabelledFactTextField {
                    label: qsTr("纬度（WGS84 Latitude）")
                    fact: rtkSettings.fixedBasePositionLatitude
                    visible: root.baseMode === BaseModeDefinition.BaseFixed
                }
                LabelledFactTextField {
                    label: qsTr("经度（WGS84 Longitude）")
                    fact: rtkSettings.fixedBasePositionLongitude
                    visible: root.baseMode === BaseModeDefinition.BaseFixed
                }
                LabelledFactTextField {
                    label: qsTr("椭球高（WGS84 Altitude）")
                    fact: rtkSettings.fixedBasePositionAltitude
                    visible: root.baseMode === BaseModeDefinition.BaseFixed
                }
                LabelledFactTextField {
                    label: qsTr("坐标精度（Position Accuracy）")
                    fact: rtkSettings.fixedBasePositionAccuracy
                    visible: root.baseMode === BaseModeDefinition.BaseFixed
                }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: qgcPal.warningText
                    text: root.baseMode === BaseModeDefinition.BaseSurveyIn
                          ? qsTr("Survey-In 必须同时达到最短观测时间和目标精度。参数修改后请断开并重新连接基准站，使配置重新应用。")
                          : qsTr("固定坐标必须是经过测量的精确 WGS84 坐标；输入普通手机定位坐标会让全部 RTK 结果产生系统性偏移。参数修改后请重新连接基准站。")
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth: true
                heading: qsTr("UM982 自动配置（Unicore UM982）")
                visible: root.selectedUnicore

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("按 Mission Planner 的 UM982 基准站方案配置 COM3（115200 baud），启动 60 秒自动测量，并输出 RTCM1006、1033、1074、1084、1094 和 1124。该方案当前只支持自动测量，不写入固定坐标。")
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth: true
                heading: qsTr("运行状态（RTK Status）")
                visible: true

                LabelledLabel { label: qsTr("状态"); labelText: !QGroundControl.gpsRtk.connected.value ? qsTr("未连接（Disconnected）") : QGroundControl.gpsRtk.rtcmFrames.rawValue > 0 ? qsTr("正在接收并转发有效 RTCM") : (QGroundControl.gpsRtk.streamBytes.rawValue > 0 ? qsTr("有串口数据，但没有有效 RTCM") : (QGroundControl.gpsRtk.active.value ? qsTr("正在自动测量（Survey-In Active）") : qsTr("等待接收机数据"))) }
                LabelledLabel { label: qsTr("串口接收量"); labelText: QGroundControl.gpsRtk.streamBytes.rawValue + " bytes" }
                LabelledLabel { label: qsTr("当前数据率"); labelText: Number(QGroundControl.gpsRtk.streamBytesPerSec.rawValue).toFixed(0) + " B/s" }
                LabelledLabel { label: qsTr("有效 RTCM 帧"); labelText: QGroundControl.gpsRtk.rtcmFrames.rawValue }
                LabelledLabel { label: qsTr("无效 RTCM 帧"); labelText: QGroundControl.gpsRtk.invalidRtcmFrames.rawValue }
                LabelledLabel { label: qsTr("最近 RTCM 类型"); labelText: QGroundControl.gpsRtk.lastRtcmMessageId.rawValue > 0 ? "RTCM" + QGroundControl.gpsRtk.lastRtcmMessageId.rawValue : "--" }
                LabelledLabel { label: qsTr("可见卫星"); labelText: QGroundControl.gpsRtk.numSatellites.value }
                LabelledLabel { label: qsTr("参与解算卫星"); labelText: root.configureReceiver && !root.selectedUnicore ? QGroundControl.gpsRtk.numSatellitesUsed.value : "--" }
                LabelledLabel { label: qsTr("观测时间"); labelText: QGroundControl.gpsRtk.currentDuration.value + " s" }
                LabelledLabel { label: qsTr("当前精度"); labelText: QGroundControl.gpsRtk.currentAccuracy.valueString + " m" }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: "#6FF4D2"
                    text: !QGroundControl.gpsRtk.connected.value ? qsTr("基准站未连接，当前没有转发改正数据。") : QGroundControl.gpsRtk.rtcmFrames.rawValue <= 0
                          ? qsTr("尚未收到有效 RTCM 改正数据；请确认选择的是 RTK 接收机串口，而不是飞控的 MAVLink 串口，并检查接收机输出协议和波特率。")
                          : QGroundControl.multiVehicleManager.vehicles.count > 0
                          ? qsTr("同一份 RTCM 改正数据正在向所有 %1 架已连接飞机转发（共用链路会自动去重）。").arg(QGroundControl.multiVehicleManager.vehicles.count)
                          : qsTr("RTCM 已就绪；连接飞机后会自动向全部飞机转发。")
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Satellite Signal（卫星信号 / C/N₀）")
                    font.bold: true
                }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    visible: QGroundControl.gpsRtk.satelliteBars.length === 0
                    text: QGroundControl.gpsRtk.connected.value
                          ? qsTr("等待卫星信号数据。直通连接需要接收机在同一串口输出 NMEA GSV；仅有 RTCM 无法显示信号柱。直通模式不会自动修改接收机配置。")
                          : qsTr("RTK 基准站未连接。连接接收机后将在此显示其实际输出的卫星信号。")
                }

                QGCFlickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                    visible: QGroundControl.gpsRtk.satelliteBars.length > 0
                    contentWidth: satelliteRow.implicitWidth
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                        id: satelliteRow
                        height: parent.height
                        spacing: ScreenTools.defaultFontPixelWidth * 0.45

                        Repeater {
                            model: QGroundControl.gpsRtk.satelliteBars

                            Column {
                                required property var modelData
                                width: ScreenTools.defaultFontPixelWidth * 4
                                height: satelliteRow.height
                                spacing: 2

                                Item {
                                    width: parent.width
                                    height: parent.height - ScreenTools.defaultFontPixelHeight * 2.2
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * 0.72
                                        height: Math.max(2, parent.height * Math.min(1, Number(modelData.snr) / 60))
                                        radius: width / 5
                                        color: Number(modelData.snr) >= 35 ? qgcPal.colorGreen : (Number(modelData.snr) >= 20 ? qgcPal.colorOrange : qgcPal.warningText)
                                    }
                                }
                                QGCLabel { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.id }
                                QGCLabel { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.snr > 0 ? modelData.snr + " dB-Hz" : "--"; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: refreshPorts()
}
