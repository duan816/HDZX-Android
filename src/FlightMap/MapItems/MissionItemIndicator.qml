import QtQuick
import QtLocation

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

/// Marker for displaying a mission item on the map
MapQuickItem {
    id: _item

    property var missionItem
    property int sequenceNumber
    readonly property bool _planViewStyle: parent && parent.planView === true

    signal clicked

    anchorPoint.x:  sourceItem.anchorPointX
    anchorPoint.y:  sourceItem.anchorPointY

    sourceItem: Loader {
        readonly property real anchorPointX: item ? item.anchorPointX : 0
        readonly property real anchorPointY: item ? item.anchorPointY : 0
        sourceComponent: _item._planViewStyle ? planIndicator : standardIndicator
    }

    Component {
        id: planIndicator
        PlanWaypointMarker {
            index: _item.sequenceNumber
            takeoff: _item.missionItem && _item.missionItem.isTakeoffItem === true
            checked: _item.missionItem && (_item.missionItem.isCurrentItem || _item.missionItem.hasCurrentChildItem)
            gimbalYaw: _item.missionItem ? _item.missionItem.missionGimbalYaw : NaN
            vehicleYaw: _item.missionItem ? _item.missionItem.missionVehicleYaw : NaN
            showGimbalYaw: !isNaN(gimbalYaw)
            onClicked: _item.clicked()
        }
    }

    Component {
        id: standardIndicator
        MissionItemIndexLabel {
            id:                 _label
            checked:            _isCurrentItem
            label:              missionItem.abbreviation
            index:              missionItem.abbreviation.charAt(0) > 'A' && missionItem.abbreviation.charAt(0) < 'z' ? -1 : missionItem.sequenceNumber
            gimbalYaw:          missionItem.missionGimbalYaw
            vehicleYaw:         missionItem.missionVehicleYaw
            showGimbalYaw:      !isNaN(missionItem.missionGimbalYaw)
            highlightSelected:  true
            onClicked:          _item.clicked()
            opacity:            _item.opacity

            property bool _isCurrentItem:   missionItem ? missionItem.isCurrentItem || missionItem.hasCurrentChildItem : false
        }
    }
}
