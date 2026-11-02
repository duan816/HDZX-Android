import QGroundControl
import QGroundControl.Controls

ToolStripAction {
    signal rebootRequested

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    text: qsTr("重启飞控")
    iconSource: "/res/PowerButton.svg"
    visible: true
    enabled: vehicle && !vehicle.armed && !vehicle.flying
    onTriggered: rebootRequested()
}
