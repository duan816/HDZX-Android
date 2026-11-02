import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    objectName:    "flyViewToolBarIndicators"
    implicitWidth: mainLayout.width + _widthMargin

    property var  _activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property real _toolIndicatorMargins:    ScreenTools.defaultFontPixelWidth * 0.75
    property real _widthMargin:             _toolIndicatorMargins * 2
    function vehicleIndicators() {
        const indicators = _activeVehicle ? _activeVehicle.toolIndicators : []
        const result = []
        for (let i=0;i<indicators.length;++i)
            if (String(indicators[i]).indexOf("/MultiVehicleSelector.qml") < 0) result.push(indicators[i])
        return result
    }

    Row {
        id:                 mainLayout
        anchors.margins:    _toolIndicatorMargins
        anchors.topMargin: parent.height * 0.035
        anchors.bottomMargin: parent.height * 0.035
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        spacing:            ScreenTools.defaultFontPixelWidth * 0.85

        Repeater {
            id:     appRepeater
            model:  QGroundControl.corePlugin.toolBarIndicators
            Loader {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             modelData
                visible:            item ? item.showIndicator : false
            }
        }

        Repeater {
            id:     toolIndicatorsRepeater
            model:  vehicleIndicators()

            Loader {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             modelData
                visible:            item ? item.showIndicator : false
            }
        }
    }
}
