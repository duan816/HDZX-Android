import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

ToolStrip {
    id: _root

    signal displayPreFlightChecklist
    signal rebootVehicleRequested

    FlyViewToolStripActionList {
        id: flyViewToolStripActionList

        onDisplayPreFlightChecklist: _root.displayPreFlightChecklist()
        onRebootVehicleRequested: _root.rebootVehicleRequested()
    }

    model: flyViewToolStripActionList.model
}
