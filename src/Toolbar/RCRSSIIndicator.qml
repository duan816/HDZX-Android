import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import "HQIndicatorMath.js" as IndicatorMath

//-------------------------------------------------------------------------
//-- RC RSSI Indicator
Item {
    id:             control
    width:          rssiRow.width * 1.1
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: !!_activeVehicle && _activeVehicle.supports.radio

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    QGCPalette { id: qgcPal }
    property bool   _rcRSSIAvailable:   !!_activeVehicle && !_activeVehicle.vehicleLinkManager.communicationLost
                                       && isFinite(IndicatorMath.percentageFraction(Number(_activeVehicle.rcRSSI.rawValue)))

    Component {
        id: rcRSSIInfoPage

        ToolIndicatorPage {
            showExpand: false

            contentComponent: SettingsGroupLayout {
                heading: qsTr("RC RSSI Status")

                LabelledLabel {
                    label:      qsTr("RSSI")
                    labelText:  _rcRSSIAvailable ? _activeVehicle.rcRSSI.rawValue + "%" : "--"
                }
            }
        }
    }

    Row {
        id:             rssiRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            width:              height
            height:             rssiRow.height * 0.52
            anchors.verticalCenter: parent.verticalCenter
            sourceSize.height:  height
            source:             "/qmlimages/RC.svg"
            fillMode:           Image.PreserveAspectFit
            opacity:            _rcRSSIAvailable ? 1 : 0.5
            color:              qgcPal.buttonText
        }

        HQCircularGauge {
            instrumentStyle: false
            anchors.verticalCenter: parent.verticalCenter
            width: rssiRow.height * 0.94
            height: width
            fraction: _rcRSSIAvailable ? IndicatorMath.percentageFraction(Number(_activeVehicle.rcRSSI.rawValue)) : NaN
            valueText: _rcRSSIAvailable ? Math.round(Number(_activeVehicle.rcRSSI.rawValue)) + "%" : "--"
            caption: qsTr("遥控")
            critical: _rcRSSIAvailable && fraction <= 0.2
            accentColor: fraction <= 0.2 ? "#FF705E" : fraction <= 0.4 ? "#FFBE55" : "#56DB99"
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(rcRSSIInfoPage, control)
    }
}
