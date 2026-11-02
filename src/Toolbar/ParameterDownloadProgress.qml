import QtQuick
import QGroundControl
import QGroundControl.Controls

// Never cover readiness, alarms or the flight-mode selector while loading.
Item {
    id: control
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var connectionAttempt: typeof mainWindow !== "undefined" ? mainWindow.hdzxConnectionAttempt : null
    readonly property bool connected: !!_activeVehicle
    readonly property bool waitingForHeartbeat: !connected && !!connectionAttempt && connectionAttempt.waiting
    readonly property bool communicationLost: connected && !!_activeVehicle.vehicleLinkManager
                                              && _activeVehicle.vehicleLinkManager.communicationLost
    readonly property bool initialComplete: !connected || _activeVehicle.initialConnectComplete
    readonly property real reportedProgress: connected ? _activeVehicle.loadProgress : NaN

    HQConnectionProgress {
        objectName: "toolbarConnectionProgress"
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 3
        clip: true
        progress: control.reportedProgress
        connected: control.connected || control.waitingForHeartbeat
        indeterminate: control.waitingForHeartbeat || !isFinite(progress) || progress <= 0
        communicationLost: control.communicationLost
        sourceToken: control._activeVehicle
        accent: control.communicationLost ? "#ff697a" : QGroundControl.globalPalette.colorGreen
        visible: !control.initialComplete || control.waitingForHeartbeat
    }
}
