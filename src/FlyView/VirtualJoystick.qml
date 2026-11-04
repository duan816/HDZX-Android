import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    // The following properties must be passed in from the Loader
    // property bool autoCenterThrottle - true: throttle will snap back to center when released
    // property bool leftHandedMode - true: virtual joystick layout will be reversed

    id: virtualJoysticks

    readonly property bool stickActive:       leftStick.touchActive || rightStick.touchActive

    property var   _activeVehicle:            QGroundControl.multiVehicleManager.activeVehicle
    property bool  _initialConnectComplete:   _activeVehicle ? _activeVehicle.initialConnectComplete : false
    property real  leftYAxisValue:            autoCenterThrottle ? (leftStick.yAxisPositiveRangeOnly ? 0.5 : 0) : (leftStick.yAxisPositiveRangeOnly ? 0 : -1)
    property real  rightYAxisValue:           autoCenterThrottle ? (rightStick.yAxisPositiveRangeOnly ? 0.5 : 0) : (rightStick.yAxisPositiveRangeOnly ? 0 : -1)
    property var   calibration:               false
    property real  uiTotalWidth:           0
    property real  uiRealX:                 0

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            if (!leftStick || !rightStick) return
            leftStick.cancelInput()
            rightStick.cancelInput()
            leftYAxisValue = autoCenterThrottle ? (leftStick.yAxisPositiveRangeOnly ? 0.5 : 0)
                                               : (leftStick.yAxisPositiveRangeOnly ? 0 : -1)
            rightYAxisValue = autoCenterThrottle ? (rightStick.yAxisPositiveRangeOnly ? 0.5 : 0)
                                                : (rightStick.yAxisPositiveRangeOnly ? 0 : -1)
            leftStick.resize(leftYAxisValue)
            rightStick.resize(rightYAxisValue)
        }
    }

    Timer {
        interval:   40  // 25Hz, same as real joystick rate
        running:    virtualJoysticks.visible && QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
        repeat:     true
        onTriggered: {
            if (_activeVehicle && _initialConnectComplete) {
                leftHandedMode ? _activeVehicle.virtualTabletJoystickValue(leftStick.xAxis, leftStick.yAxis, rightStick.xAxis, rightStick.yAxis) : _activeVehicle.virtualTabletJoystickValue(rightStick.xAxis, rightStick.yAxis, leftStick.xAxis, leftStick.yAxis)
            }
            rightYAxisValue = rightStick.yAxis
            leftYAxisValue = leftStick.yAxis // We keep Y axis value from the throttle stick for using it while there is a resize
        }
    }

    onHeightChanged:        { keepYAxisWhileChanged() }
    onWidthChanged:         { keepXAxisWhileChanged() }
    onVisibleChanged:       { if (visible) keepYAxisWhileChanged() }
    onCalibrationChanged:   { calibration ? calibrateJoysticks() : undefined }

    function calibrateJoysticks() {
        if( virtualJoysticks.visible ) {
        keepXAxisWhileChanged()
        leftYAxisValue = leftStick.yAxisReCentered() // Keep track of the correct leftYAxisValue while the width is adjusted at first start up
        }
    }

    function keepYAxisWhileChanged () {
        if (!leftStick || !rightStick) return
        leftStick.cancelInput()
        rightStick.cancelInput()
        leftStick.resize(!leftHandedMode && !autoCenterThrottle ? leftYAxisValue : (leftStick.yAxisPositiveRangeOnly ? 0.5 : 0))
        rightStick.resize(leftHandedMode && !autoCenterThrottle ? rightYAxisValue : (rightStick.yAxisPositiveRangeOnly ? 0.5 : 0))
    }

    function keepXAxisWhileChanged () {
        if( virtualJoysticks.visible ) {
            leftStick.reCenter()
            rightStick.reCenter()
        }
    }

    JoystickThumbPad {
        id:                     leftStick
        objectName:             "virtualJoystickLeftPad"
        anchors.leftMargin:     xPositionDelta
        anchors.bottomMargin:   -yPositionDelta
        anchors.left:           parent.left
        anchors.bottom:         parent.bottom
        width:                  parent.height
        height:                 parent.height
        yAxisPositiveRangeOnly: _activeVehicle && !_activeVehicle.rover && !leftHandedMode
        yAxisReCenter:          leftHandedMode ? true : autoCenterThrottle
    }

    JoystickThumbPad {
        id:                     rightStick
        objectName:             "virtualJoystickRightPad"
        anchors.rightMargin:    -xPositionDelta
        anchors.bottomMargin:   -yPositionDelta
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        width:                  parent.height
        height:                 parent.height
        yAxisPositiveRangeOnly: _activeVehicle && !_activeVehicle.rover && leftHandedMode
        yAxisReCenter:          leftHandedMode ? autoCenterThrottle : true
    }
}
