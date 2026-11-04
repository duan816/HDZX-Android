pragma Singleton
import QtQuick
QtObject {
    readonly property int zOrderTopMost: 1000
    readonly property var videoManager: QtObject { property bool fullScreen: false }
    readonly property var globalPalette: QtObject { property color text: "white"; property color window: "#102030" }
    readonly property var testVehicle: QtObject {
        property bool usingHighLatencyLink: false
        property bool rover: false
        property bool initialConnectComplete: true
        property var axes: []
        property int frames: 0
        function virtualTabletJoystickValue(roll, pitch, yaw, throttle) { axes = [roll, pitch, yaw, throttle]; ++frames }
    }
    readonly property var multiVehicleManager: QtObject { property var activeVehicle: QGroundControl.testVehicle }
    readonly property var settingsManager: QtObject {
        readonly property var appSettings: QtObject {
            readonly property var virtualJoystickAutoCenterThrottle: QtObject { property bool rawValue: true }
            readonly property var virtualJoystickLeftHandedMode: QtObject { property bool rawValue: false }
            readonly property var virtualJoystickSize: QtObject { property int rawValue: 100 }
            readonly property var virtualJoystick: QtObject { property bool rawValue: true }
        }
    }
}
