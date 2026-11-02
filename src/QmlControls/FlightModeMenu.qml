import QtQuick
import QtQuick.Controls
import QtQml.Models

import QGroundControl
import QGroundControl.Controls

QGCLabel {
    id: root
    text: currentVehicle ? currentVehicle.flightMode : qsTr("N/A", "No data to display")
    property var currentVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real mouseAreaLeftMargin: 0
    onCurrentVehicleChanged: flightModesMenu.close()

    Menu {
        id: flightModesMenu
        objectName: "vehicleFlightModeMenu"
        // Model ownership releases old menu entries. Global active-vehicle
        // notifications previously leaked parentless items in every vehicle card.
        Instantiator {
            model: root.currentVehicle && root.currentVehicle.flightModeSetAvailable ? root.currentVehicle.flightModes : []
            delegate: MenuItem {
                required property string modelData
                text: modelData
                onTriggered: {
                    const vehicle = root.currentVehicle
                    if (vehicle && vehicle.flightModeSetAvailable && vehicle.flightModes.indexOf(modelData) >= 0)
                        vehicle.flightMode = modelData
                }
            }
            onObjectAdded: (index, object) => flightModesMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => flightModesMenu.removeItem(object)
        }
    }
    MouseArea {
        visible: root.currentVehicle && root.currentVehicle.flightModeSetAvailable
        anchors.leftMargin: root.mouseAreaLeftMargin
        anchors.fill: parent
        onClicked: flightModesMenu.popup((root.width - flightModesMenu.width) / 2, root.height)
    }
}
