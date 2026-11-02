import QtQuick

// Presentation state only: never opens, closes or writes to a link/vehicle.
Item {
    id: root
    property var vehicleManager: null
    property var configuration: null
    property bool waiting: false
    property bool failed: false
    property string failureText: ""
    property bool sawLink: false
    property int timeoutMs: 30000

    function begin(config) {
        configuration = config
        sawLink = !!config && !!config.link
        failed = false
        failureText = ""
        waiting = !!config
        deadline.restart()
    }
    function finish() {
        waiting = false
        failed = false
        failureText = ""
        configuration = null
        deadline.stop()
    }
    function fail(message) {
        waiting = false
        failed = true
        failureText = message
        deadline.stop()
    }
    function checkVehicle(vehicle) {
        if (configuration && vehicle && vehicle.vehicleLinkManager
                && vehicle.vehicleLinkManager.linkNames.indexOf(configuration.name) >= 0) finish()
    }
    function checkStarted() {
        if (!configuration) return
        if (configuration.link) {
            sawLink = true
            if (vehicleManager) checkVehicle(vehicleManager.activeVehicle)
        }
        else if (waiting) fail(qsTr("连接未建立 · 检查端口与权限"))
    }
    Connections {
        target: root.configuration
        function onLinkChanged() {
            if (root.configuration && root.configuration.link) root.sawLink = true
            else if (root.waiting && root.sawLink) root.fail(qsTr("链路已关闭 · 点击重新连接"))
        }
    }
    Connections {
        target: root.vehicleManager
        function onVehicleAdded(vehicle) { root.checkVehicle(vehicle) }
        function onActiveVehicleChanged(vehicle) { root.checkVehicle(vehicle) }
    }
    Timer {
        id: deadline
        interval: root.timeoutMs
        onTriggered: root.fail(qsTr("等待心跳超时 · 检查协议与波特率"))
    }
}
