import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import "HQIndicatorMath.js" as IndicatorMath

// Used as the base class control for nboth VehicleGPSIndicator and RTKGPSIndicator

Item {
    id:             control
    width:          gpsIndicatorRow.width
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _rtkConnected:  QGroundControl.gpsRtk.connected.value
    property bool   _gps2Available: !!_activeVehicle && IndicatorMath.gpsPresent(_activeVehicle.gps2)

    QGCPalette { id: qgcPal }

    Row {
        id:             gpsIndicatorRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        Row {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            spacing:        ScreenTools.defaultFontPixelWidth * 0.2

            QGCLabel {
                id:                     gpsLabel
                rotation:               90
                text:                   qsTr("RTK")
                color:                  qgcPal.text
                anchors.verticalCenter: parent.verticalCenter
                visible:                _rtkConnected
            }


            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                objectName:             "gpsReceiverBadge"
                visible:                !!control._activeVehicle
                text:                   control._gps2Available ? "GPS2" : "GPS1"
                color:                  qgcPal.text
                font.bold:              true
                font.pixelSize:         Math.max(ScreenTools.defaultFontPixelHeight * 0.5, control.height * 0.20)
            }

            QGCColoredImage {
                id:                 gpsIcon
                width:              height
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             "/qmlimages/Gps.svg"
                fillMode:           Image.PreserveAspectFit
                sourceSize.height:  height
                opacity:            (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? 1 : 0.5
                color:              qgcPal.text
            }
        }

        Column {
            id:                     gpsValuesColumn
            anchors.verticalCenter: parent.verticalCenter
            visible:                _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)
            spacing:                0

            QGCLabel {
                anchors.horizontalCenter:   hdopValue.horizontalCenter
                color:              qgcPal.text
                text:               _activeVehicle ? _activeVehicle.gps.count.valueString : ""
            }

            QGCLabel {
                id:     hdopValue
                color:  qgcPal.text
                text:   _activeVehicle ? _activeVehicle.gps.hdop.value.toFixed(1) : ""
            }
        }


        Column {
            anchors.verticalCenter: parent.verticalCenter
            visible:                _gps2Available && !isNaN(Number(_activeVehicle.gps2.hdop.value))
            spacing:                0

            QGCLabel {
                anchors.horizontalCenter: gps2Hdop.horizontalCenter
                color: qgcPal.text
                text:  _activeVehicle ? _activeVehicle.gps2.count.valueString : ""
            }

            QGCLabel {
                id:    gps2Hdop
                color: qgcPal.text
                text:  _activeVehicle ? Number(_activeVehicle.gps2.hdop.value).toFixed(1) : ""
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(gpsIndicatorPage, control)
    }

    Component {
        id: gpsIndicatorPage

        GPSIndicatorPage { }
    }
}
