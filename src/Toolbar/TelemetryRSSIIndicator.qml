import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import "HQIndicatorMath.js" as IndicatorMath

//-------------------------------------------------------------------------
//-- Telemetry RSSI
Item {
    id:             control
    objectName:     "toolbar_telemetryRSSIIndicator"
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          signalGauge.width

    property bool showIndicator: !!_activeVehicle

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property var  _radioStatus:     _activeVehicle ? _activeVehicle.radioStatus : null
    property bool _hasTelemetry:    !!_radioStatus && _radioStatus.telemetryAvailable
                                   && !_activeVehicle.vehicleLinkManager.communicationLost
                                   && isFinite(IndicatorMath.signalFraction(Number(_radioStatus.lrssi.rawValue)))

    HQCircularGauge {
        instrumentStyle: false
        id: signalGauge
        anchors.verticalCenter: parent.verticalCenter
        width: control.height * 0.94
        height: width
        fraction: _hasTelemetry ? IndicatorMath.signalFraction(Number(_radioStatus.lrssi.rawValue)) : NaN
        valueText: _hasTelemetry ? Math.round(Number(_radioStatus.lrssi.rawValue)).toString() : "--"
        caption: qsTr("数传 dBm")
        critical: _hasTelemetry && fraction <= 0.2
        accentColor: fraction <= 0.2 ? "#FF705E" : fraction <= 0.4 ? "#FFBE55" : "#56DB99"
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(telemRSSIInfoPage, control)
    }

    Component {
        id: telemRSSIInfoPage

        ToolIndicatorPage {
            showExpand: false

            contentComponent: SettingsGroupLayout {
                heading: qsTr("Telemetry RSSI Status")

                LabelledLabel {
                    label:      qsTr("Local RSSI:")
                    labelText:  _hasTelemetry ? _radioStatus.lrssi.rawValue + " " + qsTr("dBm") : "--"
                }

                LabelledLabel {
                    label:      qsTr("Remote RSSI:")
                    labelText:  _hasTelemetry ? _radioStatus.rrssi.rawValue + " " + qsTr("dBm") : "--"
                }

                LabelledLabel {
                    label:      qsTr("RX Errors:")
                    labelText:  _hasTelemetry ? _radioStatus.rxErrors.rawValue : "--"
                }

                LabelledLabel {
                    label:      qsTr("Errors Fixed:")
                    labelText:  _hasTelemetry ? _radioStatus.fixed.rawValue : "--"
                }

                LabelledLabel {
                    label:      qsTr("TX Buffer:")
                    labelText:  _hasTelemetry ? _radioStatus.txBuffer.rawValue : "--"
                }

                LabelledLabel {
                    label:      qsTr("Local Noise:")
                    labelText:  _hasTelemetry ? _radioStatus.lNoise.rawValue : "--"
                }

                LabelledLabel {
                    label:      qsTr("Remote Noise:")
                    labelText:  _hasTelemetry ? _radioStatus.rNoise.rawValue : "--"
                }
            }
        }
    }
}
