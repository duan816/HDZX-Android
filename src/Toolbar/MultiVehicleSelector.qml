import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

RowLayout {
    id:         control
    spacing:    0

    property var    _idConflicts:         QGroundControl.multiVehicleManager.idConflicts
    property bool   showIndicator:        _multipleVehicles || (_idConflicts && _idConflicts.hasConflicts)
    property var    _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property bool   _multipleVehicles:    QGroundControl.multiVehicleManager.vehicles.count > 1
    property int    _vehicleCount:        QGroundControl.multiVehicleManager.vehicles.count

    RowLayout {
        Layout.fillWidth: true

        QGCColoredImage {
            width:      ScreenTools.defaultFontPixelWidth * 4
            height:     ScreenTools.defaultFontPixelHeight * 1.33
            fillMode:   Image.PreserveAspectFit
            mipmap:     true
            color:      control._idConflicts && control._idConflicts.hasConflicts ? qgcPal.warningText : qgcPal.text
            source:     "/InstrumentValueIcons/airplane.svg"
        }

        QGCLabel {
            text:               control._idConflicts && control._idConflicts.hasConflicts
                                    ? qsTr("编号冲突 · 点击分配")
                                    : _activeVehicle
                                    ? qsTr("%1 架 · 主机 %2").arg(_vehicleCount).arg(_activeVehicle.id)
                                    : qsTr("N/A")
            font.pointSize:     ScreenTools.mediumFontPointSize
            Layout.alignment:   Qt.AlignCenter

            MouseArea {
                anchors.fill:   parent
                onClicked:      mainWindow.showIndicatorDrawer(vehicleSelectorDrawer, control)
            }
        }
    }

    Component {
        id: vehicleSelectorDrawer

        ToolIndicatorPage {
            showExpand: false

            contentComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("多机快捷监视与切换")
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    FactCheckBoxSlider {
                        Layout.fillWidth:true
                        text:qsTr("在主界面显示多机面板")
                        fact:QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("每架飞机使用独立编号。检测到冲突时，可在下方确认自动分配，无需进入参数页。")
                        wrapMode: Text.WordWrap
                        color: qgcPal.warningText
                        font.pointSize: ScreenTools.smallFontPointSize
                    }

                    VehicleIdConflictPanel {
                        Layout.fillWidth: true
                        visible: control._idConflicts && (control._idConflicts.hasConflicts || control._idConflicts.lastResult.length > 0)
                        conflictManager: control._idConflicts
                    }

                    Repeater {
                        model: QGroundControl.multiVehicleManager.vehicles

                        Rectangle {
                            id: vehicleCard
                            Layout.fillWidth: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 42
                            Layout.preferredHeight: cardColumn.implicitHeight + ScreenTools.defaultFontPixelHeight
                            color: _vehicle === control._activeVehicle ? qgcPal.buttonHighlight : qgcPal.windowShade
                            border.width: 1
                            border.color: _vehicle === control._activeVehicle ? qgcPal.colorGreen : qgcPal.groupBorder
                            radius: ScreenTools.defaultBorderRadius

                            property var _vehicle: object

                            ColumnLayout {
                                id: cardColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: ScreenTools.defaultFontPixelWidth
                                spacing: ScreenTools.defaultFontPixelHeight * 0.3

                                RowLayout {
                                    Layout.fillWidth: true
                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: vehicleCard._vehicle
                                                ? qsTr("%1 号机 · %2").arg(vehicleCard._vehicle.id).arg(vehicleCard._vehicle.firmwareTypeString)
                                                : ""
                                        font.bold: true
                                    }
                                    QGCLabel {
                                        text: vehicleCard._vehicle === control._activeVehicle ? qsTr("主调试") : ""
                                        color: qgcPal.colorGreen
                                        font.bold: true
                                    }
                                    QGCButton {
                                        text: qsTr("切换")
                                        enabled: vehicleCard._vehicle && vehicleCard._vehicle !== control._activeVehicle
                                        onClicked: QGroundControl.multiVehicleManager.activeVehicle = vehicleCard._vehicle
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: ScreenTools.defaultFontPixelWidth

                                    QGCLabel { text: qsTr("飞行模式") }
                                    QGCComboBox {
                                        Layout.fillWidth: true
                                        enabled: vehicleCard._vehicle && vehicleCard._vehicle.flightModeSetAvailable
                                        model: vehicleCard._vehicle ? vehicleCard._vehicle.flightModes : []
                                        currentIndex: vehicleCard._vehicle ? vehicleCard._vehicle.flightModes.indexOf(vehicleCard._vehicle.flightMode) : -1
                                        onActivated: {
                                            if (vehicleCard._vehicle && currentIndex >= 0)
                                                vehicleCard._vehicle.flightMode = currentText
                                        }
                                    }

                                    QGCLabel { text: qsTr("位置") }
                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: vehicleCard._vehicle && vehicleCard._vehicle.coordinate.isValid
                                                ? qsTr("纬度 %1  经度 %2")
                                                    .arg(vehicleCard._vehicle.coordinate.latitude.toFixed(6))
                                                    .arg(vehicleCard._vehicle.coordinate.longitude.toFixed(6))
                                                : qsTr("尚未定位")
                                    }

                                    QGCLabel { text: qsTr("链路 / 消息") }
                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: vehicleCard._vehicle
                                                ? (vehicleCard._vehicle.vehicleLinkManager.communicationLost
                                                   ? qsTr("通信中断")
                                                   : qsTr("已连接 · %1 条消息").arg(vehicleCard._vehicle.messageCount))
                                                : ""
                                        color: vehicleCard._vehicle && (vehicleCard._vehicle.vehicleLinkManager.communicationLost || vehicleCard._vehicle.messageTypeError)
                                                ? qgcPal.warningText : qgcPal.text
                                    }
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    visible: vehicleCard._vehicle && vehicleCard._vehicle.prearmError !== ""
                                    text: vehicleCard._vehicle ? vehicleCard._vehicle.prearmError : ""
                                    wrapMode: Text.WordWrap
                                    color: qgcPal.warningText
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                            }
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("关闭")
                        onClicked: mainWindow.closeIndicatorDrawer()
                    }
                }
            }

            expandedComponent: Component {
                SettingsGroupLayout {
                    Layout.fillWidth: true

                    FactCheckBoxSlider {
                        Layout.fillWidth:   true
                        text:               qsTr("Enable Multi-Vehicle Panel")
                        fact:               _enableMultiVehiclePanel
                        visible:            _enableMultiVehiclePanel.visible

                        property Fact _enableMultiVehiclePanel: QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel
                    }
                }
            }
        }
    }

}
