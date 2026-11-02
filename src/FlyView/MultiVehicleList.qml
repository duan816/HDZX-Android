import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.FlyView

Item {
    property real   _margin:              ScreenTools.defaultFontPixelWidth / 2
    property real   _widgetHeight:        ScreenTools.defaultFontPixelHeight * 2.5
    property var    _guidedController:    globals.guidedControllerFlyView
    property var    _activeVehicleColor:  "green"
    property var    _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property var    selectedVehicles:     QGroundControl.multiVehicleManager.selectedVehicles

    implicitHeight: vehicleList.contentHeight
    implicitWidth: ScreenTools.defaultFontPixelWidth * 36

    function armAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === false) {
                return true
            }
        }
        return false
    }


    function disarmAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === true) {
                return true
            }
        }
        return false
    }

    function startAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === true && vehicle.flightMode !== vehicle.missionFlightMode){
                return true
            }
        }
        return false
    }

    function pauseAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === true && vehicle.supports.pauseVehicle) {
                return true
            }
        }
        return false
    }

    function selectVehicle(vehicleId) {
        QGroundControl.multiVehicleManager.selectVehicle(vehicleId)
    }

    function deselectVehicle(vehicleId) {
        QGroundControl.multiVehicleManager.deselectVehicle(vehicleId)
    }

    function toggleSelect(vehicleId) {
        if (!vehicleSelected(vehicleId)) {
            selectVehicle(vehicleId)
        } else {
            deselectVehicle(vehicleId)
        }
    }

    function selectAll() {
        var vehicles = QGroundControl.multiVehicleManager.vehicles
        for (var i = 0; i < vehicles.count; i++) {
            var vehicle = vehicles.get(i)
            var vehicleId = vehicle.id
            if (!vehicleSelected(vehicleId)) {
                selectVehicle(vehicleId)
            }
        }
    }

    function deselectAll() {
        QGroundControl.multiVehicleManager.deselectAllVehicles()
    }

    function vehicleSelected(vehicleId) {
        for (var i = 0; i < selectedVehicles.count; i++ ) {
            var currentId = selectedVehicles.get(i).id
            if (vehicleId === currentId) {
                return true
            }
        }
        return false
    }

    QGCListView {
        id:                 vehicleList
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        spacing:            ScreenTools.defaultFontPixelWidth * 0.75 // _layoutMargin
        orientation:        ListView.Vertical
        model:              QGroundControl.multiVehicleManager.vehicles
        cacheBuffer:        _cacheBuffer < 0 ? 0 : _cacheBuffer
        clip:               true

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.65; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
        }

        property real _cacheBuffer:     height * 2

        delegate: HQVehicleCard {
            required property var object
            width: vehicleList.width
            vehicle: object
            current: vehicle === QGroundControl.multiVehicleManager.activeVehicle
            selected: vehicle && vehicleSelected(vehicle.id)
            onActivateRequested: if (vehicle) QGroundControl.multiVehicleManager.activeVehicle = vehicle
            onSelectionRequested: if (vehicle) toggleSelect(vehicle.id)
        }
    }
}
